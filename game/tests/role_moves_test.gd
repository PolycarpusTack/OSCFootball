extends SceneTree
## The Chaos role moves: ↓↘→ + shoot does each line's own move (LineMoves), and each line has
## a signature special (ChaosActions). Real Match nodes, physics off, steps driven by hand.
var m: Node
var actions: Node
var anims: Node
var failed := 0


func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		push_error(message)


func reset() -> void:
	actions.clear()
	m.state = 1
	m._offside.clear()
	m.referee_cone = false
	for t in [m.home, m.away]:
		t.energy = 100.0
		for i in t.players.size():
			var p = t.players[i]
			p.position = Vector2(300 + i * 40, 100 if t == m.home else 1000)  # out of everyone's way
			p._action_left = 0.0
			p.chaos_lock = false
			p.dizzy_left = 0.0
			p.touch_cooldown = 0.0
			p.sent_off = false
			p.velocity = Vector2.ZERO
			p.discipline = 0.0
	m.ball.stop_at(Vector2(900, 500))
	m.ball.prev_position = m.ball.position
	m.ball.last_touch = null


## The first player of `t` on line `role`, placed at `at` (the ball at his feet when `ball`).
func on_line(t, role: String, at: Vector2, ball := false):
	var p = t.players.filter(func(q): return q.role == role)[0]
	p.position = at
	p.facing = anims.facing_from(Vector2(t.side, 0))
	if ball:
		m.ball.stop_at(p.feet_front())
		m.ball.take(p)
	return p


## Let a line move's wind-up run out: its contact is on a timer.
func past_contact() -> void:
	await create_timer(m.line_moves.LIST.D.contact + 0.1).timeout


func contact(id: String) -> void:
	actions.tick(float(actions.MOVES[id].wind) + 0.01)


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.get_script().chaos = true
	m.get_script().players = 2
	root.add_child(m)
	await process_frame
	anims = root.get_node("Anims")
	m.set_physics_process(false)
	for t in [m.home, m.away]:
		for p in t.players:
			p.set_physics_process(false)
	m.ball.set_physics_process(false)
	actions = m.chaos_actions
	actions.ai_enabled = false
	var b = m.ball
	var side: int = m.home.side
	var mid: Vector2 = Pitch.field_rect().get_center()
	var events := []
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))

	# the line moves: in Pixel a FIFA 96 stand-in in the palette kit, in Rendered the Blender
	# art in its own; either way as long as the drawn art (the move's timing)
	for anim in ["power_strike", "bulldozer_clear", "laser_pass", "cannon_punt", "grapple_tackle", "stepover_storm", "whirlwind_turn", "rising_fist"]:
		check(anims.has(anim) and not anims.own_art(anim), "%s loads, drawn with the kit shader" % anim)
	check(absf(anims.length_seconds("power_strike") - 0.85) < 0.01, "Line-move length is the drawn art's: %.2f" % anims.length_seconds("power_strike"))
	check(absf(anims.length_seconds("stepover_storm") - 0.61) < 0.01, "Stepover Storm keeps its 0.61 s: %.2f" % anims.length_seconds("stepover_storm"))
	reset()
	var d = on_line(m.home, "D", mid)
	d.perform("bulldozer_clear")
	d._physics_process(0.0)
	check(d._sprite.material == d._kit and (d._sprite.texture as AtlasTexture).atlas.resource_path.ends_with("players/divehed.png"),
		"Pixel: Bulldozer Clear plays FIFA 96's diving header in the team's kit")
	d._action_left = 0.0
	d._physics_process(0.0)
	m.get_script().rendered = true
	d.perform("bulldozer_clear")
	d._physics_process(0.0)
	check(d._sprite.material == d._rendered_kit and (d._sprite.texture as AtlasTexture).atlas.resource_path.ends_with("oscf_rendered/bulldozer_clear.png"),
		"Rendered: Bulldozer Clear plays its Blender art in the team's kit")
	check(absf(anims.length_seconds("power_strike") - 0.85) < 0.01, "Rendered line move as long as the drawn art: %.2f" % anims.length_seconds("power_strike"))
	d._action_left = 0.0
	d._physics_process(0.0)
	var g = m.home.keeper()
	g.perform("cannon_punt")
	g._physics_process(0.0)
	check(g._sprite.material == g._rendered_kit and g._rendered_kit.get_shader_parameter("shirt") == m.home.keeper_material.get_shader_parameter("shirt"),
		"Keeper's Cannon Punt in the keeper kit")
	g._action_left = 0.0
	g._physics_process(0.0)
	m.get_script().rendered = false

	# striker: ↓↘→ is still the Fireball, wound up with the Power Strike
	reset()
	var f = on_line(m.home, "F", mid, true)
	events.clear()
	check(m.combo_move(f, "fireball", m.home.goal_attacked(), Vector2(side, 0)), "Striker's ↓↘→ fires")
	check(f._anim == "power_strike", "Fireball wound up with the Power Strike art")
	await past_contact()
	check(b.power == "fireball" and events.has("fireball:" + m.home.short) and m.home.energy == 50.0, "Striker's ↓↘→ is a Fireball")

	# defender: the Bulldozer charges, flattens whoever's in the way, then clears upfield
	reset()
	d = on_line(m.home, "D", mid, true)
	var o = on_line(m.away, "M", mid + Vector2(side * 18.0, 0.0))
	events.clear()
	check(m.combo_move(d, "fireball", Vector2.ZERO, Vector2(side, 0)), "Defender's ↓↘→ starts")
	check(d._anim == "bulldozer_clear" and d.velocity.x * side > 200.0, "Bulldozer charges")
	m.line_moves.tick()
	check(o.busy() and o._anim == "fall" and o.touch_cooldown > 0.0, "Bulldozer flattens the man in the way")
	check(o.position.distance_to(mid) < 30.0 and d.discipline > 0.0, "... and the referee notes it")
	o._action_left = 0.0
	m.line_moves.tick()
	check(not o.busy(), "Flattened once per charge")
	await past_contact()
	check(b.holder == null and b.velocity.x * side > 500.0 and b.vz > 200.0 and b.kick_kind == "clear", "Bulldozer clears it high upfield")
	check(m.home.energy == 60.0 and events.has("bulldozer:" + m.home.short), "Bulldozer costs 40, once it connects")
	check(m.line_moves._charging.is_empty(), "Charge over after the kick")

	reset()  # aimed back at his own goal, it still goes upfield
	d = on_line(m.home, "D", mid, true)
	m.combo_move(d, "fireball", Vector2.ZERO, Vector2(-side, 0.3))
	await past_contact()
	check(b.velocity.x * side > 0.0, "A clearance never goes back toward his own goal")

	reset()  # robbed in the wind-up: nothing spent
	d = on_line(m.home, "D", mid, true)
	o = on_line(m.away, "M", mid + Vector2(0, 200))
	events.clear()
	m.combo_move(d, "fireball", Vector2.ZERO, Vector2(side, 0))
	b.take(o)
	await past_contact()
	check(b.holder == o and m.home.energy == 100.0 and events.is_empty(), "Lost in the wind-up costs nothing")

	# midfielder: the Laser Pass, flat, fast and straight to the man
	reset()
	var mf = on_line(m.home, "M", mid, true)
	var mate = m.home.players.filter(func(q): return q.role == "F")[0]
	mate.position = mid + Vector2(side * 300.0, 40.0)
	check(m.combo_move(mf, "fireball", Vector2.ZERO, Vector2(side, 0)), "Midfielder's ↓↘→ starts")
	await past_contact()
	var to_mate: Vector2 = (mate.position - b.position).normalized()
	check(b.velocity.length() > 700.0 and b.velocity.normalized().dot(to_mate) > 0.99 and b.vz == 0.0, "Laser Pass: flat, fast, at the mate")
	check(b.kick_kind == "pass" and m.home.energy == 70.0 and b.power == "", "Laser Pass is a pass (no super), costs 30")

	# keeper: the Cannon Punt from the hands, once the box is clear
	reset()
	var k = m.home.keeper()
	k.position = m.home.goal_defended() + Vector2(side * Pitch.m(5.0), 0.0)
	b.stop_at(k.feet_front())
	b.take(k)
	o = on_line(m.away, "F", k.position + Vector2(side * 30.0, 0.0))
	check(not m.combo_move(k, "fireball", Vector2.ZERO, Vector2(side, 0)), "No punt while opponents crowd the box")
	o.position = mid
	m._keeper_held = 0.0
	check(m.combo_move(k, "fireball", Vector2.ZERO, Vector2(side, 0)), "Keeper's ↓↘→ starts")
	await past_contact()
	check(b.holder == null and b.velocity.x * side > 600.0 and b.vz > 300.0 and m.home.energy == 70.0, "Cannon Punt: far upfield, costs 30")

	# not without the bar, not in Classic
	reset()
	mf = on_line(m.home, "M", mid, true)
	m.home.energy = 20.0
	check(not m.combo_move(mf, "fireball", Vector2.ZERO, Vector2(side, 0)) and not mf.busy(), "No line move with too little energy")
	m.home.energy = 100.0
	m.get_script().chaos = false
	check(not m.combo_move(mf, "fireball", Vector2.ZERO, Vector2(side, 0)) and m.home.energy == 100.0, "No line moves in Classic")
	m.get_script().chaos = true

	# defender's signature: the Grapple Tackle wraps up the carrier and comes away with it
	reset()
	d = on_line(m.home, "D", mid)
	o = on_line(m.away, "M", mid + Vector2(side * 22.0, 0.0), true)
	mf = on_line(m.home, "M", mid + Vector2(0, -200))
	check(actions.unavailable(mf, "grapple") != "", "Only a defender grapples")
	check(actions.start(d, "grapple", Vector2(side, 0)), "Grapple starts")
	contact("grapple")
	check(b.holder == d and actions.stuns.has(o) and m.home.energy == 65.0, "Grapple takes the ball and holds the carrier")
	reset()
	d = on_line(m.home, "D", mid)
	o = on_line(m.away, "M", mid + Vector2(side * 80.0, 0.0), true)
	check(actions.unavailable(d, "grapple") != "", "Grapple needs the carrier right by him")

	# midfielder or striker's Stepover Storm: the man in front freezes, the ball stays
	reset()
	f = on_line(m.home, "F", mid, true)
	o = on_line(m.away, "D", mid + Vector2(side * 30.0, 0.0))
	check(actions.start(f, "stepover", Vector2(side, 0)), "Stepover starts")
	contact("stepover")
	check(actions.stuns.has(o) and actions.stuns[o].left > 0.9 and b.holder == f, "Stepover freezes the man in front; he keeps the ball")
	reset()
	f = on_line(m.home, "F", mid, true)
	check(actions.unavailable(f, "stepover") != "", "Stepover needs a man in front")

	# midfielder's Whirlwind Turn: spins away with it, nobody gets a foot in
	reset()
	mf = on_line(m.home, "M", mid, true)
	o = on_line(m.away, "D", mid + Vector2(side * 20.0, 0.0))
	check(actions.start(mf, "whirlwind", Vector2(0, 1)), "Whirlwind starts")
	contact("whirlwind")
	actions.tick(0.1)
	check(o.touch_cooldown > 0.0 and b.holder == mf and mf.position.y > mid.y + 5.0, "Whirlwind shields the ball and turns away")
	d = on_line(m.home, "D", mid + Vector2(0, 200), true)
	check(actions.unavailable(d, "whirlwind") != "", "Only a midfielder whirls")

	# keeper's Rising Fist: punches a high ball in his box clear, upfield
	reset()
	k = m.home.keeper()
	k.position = m.home.goal_defended() + Vector2(side * Pitch.m(6.0), 0.0)
	b.stop_at(k.position + Vector2(side * 20.0, 0.0))
	b.z = 60.0
	b.velocity = Vector2(-side * 300.0, 0.0)
	b.prev_position = b.position
	m.humans[0].controlled = on_line(m.home, "M", mid)
	check(actions.actor(m.humans[0], "fist") == k, "Rising Fist routes to the keeper")
	check(actions.start(k, "fist", Vector2(-side, 0)), "Rising Fist starts")
	contact("fist")
	check(b.velocity.x * side > 0.0 and b.kick_kind == "save" and b.last_touch == k, "Rising Fist punches it clear, upfield")
	reset()
	k.position = m.home.goal_defended() + Vector2(side * Pitch.m(6.0), 0.0)
	b.stop_at(k.position + Vector2(side * 20.0, 0.0))
	check(actions.unavailable(k, "fist") != "", "Rising Fist needs a ball in the air")

	print("ROLE MOVES TEST %s" % ("PASSED" if failed == 0 else "FAILED (%d)" % failed))
	quit(0 if failed == 0 else 1)
