extends SceneTree
## The Chaos modifiers: each one only with its toggle on, and never in Classic. Super goalie
## doubles a keeper's reach; crazy bounce sends the ball up higher and off at an angle; hot
## potato knocks the ball off anyone but a keeper after HOT_POTATO seconds; giant players
## draws them bigger. The match options list them in Chaos Football only.
## godot --headless --path game -s res://tests/modifiers_test.gd

var m: Node
var match_script: GDScript  # Match; the class can't be named here


func _initialize() -> void:
	seed(3)
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	match_script = m.get_script()
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	var ok := true
	var keeper = m.home.keeper()
	var runner = m.home.players[6]

	# none on: everything as before
	match_script.modifiers.clear()
	var reach: float = m.keeper_reach(keeper)
	var plain_bounce: Vector2 = await _bounce()
	print("no modifiers: keeper reach %.1f, bounce %s" % [reach, plain_bounce])

	# super goalie
	match_script.modifiers.assign(["super goalie"])
	print("super goalie: reach %.1f (was %.1f)" % [m.keeper_reach(keeper), reach])
	ok = ok and is_equal_approx(m.keeper_reach(keeper), reach * 2.0)

	# crazy bounce: higher, and the line changes
	match_script.modifiers.assign(["crazy bounce"])
	var crazy: Vector2 = await _bounce()
	print("crazy bounce: up %.0f (plain %.0f), off line %.2f rad" % [crazy.x, plain_bounce.x, crazy.y])
	ok = ok and crazy.x > plain_bounce.x * 1.5 and is_zero_approx(plain_bounce.y) and crazy.y > 0.05

	# hot potato: off his foot after HOT_POTATO seconds; a keeper keeps it
	match_script.modifiers.assign(["hot potato"])
	m.ball.stop_at(runner.feet_front())
	m.ball.take(runner)
	m._potato_left = match_script.HOT_POTATO
	m._hot_potato(match_script.HOT_POTATO - 0.1)
	var still: bool = m.ball.holder == runner
	m._hot_potato(0.2)
	var popped: bool = m.ball.holder == null and m.ball.velocity.length() > 100.0 and runner.touch_cooldown > 0.0
	m.ball.stop_at(keeper.feet_front())
	m.ball.take(keeper)
	m._hot_potato(match_script.HOT_POTATO + 1.0)
	print("hot potato: kept at %.1f s %s, off his foot after %s, keeper keeps it %s" % [match_script.HOT_POTATO - 0.1,
		still, popped, m.ball.holder == keeper])
	ok = ok and still and popped and m.ball.holder == keeper

	# giant players: drawn bigger
	match_script.modifiers.assign(["giant players"])
	runner.place(Vector3(100, 100, 1.0))
	var giant: float = runner._sprite.scale.x
	match_script.modifiers.clear()
	runner.place(Vector3(100, 100, 1.0))
	print("giant players: scale %.1f, off %.1f" % [giant, runner._sprite.scale.x])
	ok = ok and giant > 1.5 and runner._sprite.scale.x == 1.0

	# Classic: the toggles do nothing
	match_script.modifiers.assign(match_script.MODIFIERS)
	match_script.chaos = false
	print("classic with all on: super goalie %s, reach %.1f" % [match_script.modifier("super goalie"), m.keeper_reach(keeper)])
	ok = ok and not match_script.modifier("super goalie") and is_equal_approx(m.keeper_reach(keeper), reach)

	# the match options: four more rows in Chaos, toggled with left / right
	var options = load("res://scripts/match_options.gd").new()
	root.add_child(options)
	await process_frame
	var classic_rows: int = options._rows().size()
	match_script.chaos = true
	match_script.modifiers.clear()
	options._refresh()
	var chaos_rows: int = options._rows().size()
	options._row = 7
	options._change(1)
	var on: Array = match_script.modifiers.duplicate()
	options._change(1)
	print("options: %d rows in Classic, %d in Chaos; row 7 toggled on %s, off %s" % [classic_rows, chaos_rows, on, match_script.modifiers])
	ok = ok and classic_rows == 7 and chaos_rows == 11 and on == ["giant players"] and match_script.modifiers.is_empty()
	options.queue_free()

	print("MODIFIERS TEST PASSED" if ok else "MODIFIERS TEST FAILED")
	quit(0 if ok else 1)


## Drop the ball from 3 m rolling along x: [how high it goes back up, how far off its line (rad)].
func _bounce() -> Vector2:
	var c: Vector2 = Pitch.field_rect().get_center()
	m.ball.stop_at(c)
	m.ball.z = 54.0
	m.ball.vz = 0.0
	m.ball.velocity = Vector2(100, 0)
	while m.ball.z > 0.0:
		await physics_frame
	await physics_frame
	var off: float = absf(m.ball.velocity.angle())
	var top := 0.0
	while m.ball.vz > 0.0:
		await physics_frame
		top = maxf(top, m.ball.z)
	return Vector2(top, off)
