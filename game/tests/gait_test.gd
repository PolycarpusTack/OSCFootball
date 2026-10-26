extends SceneTree
## How a player's run, jog and walk are drawn (slice 2, S-2): a gait doesn't flicker at its
## threshold, a change of gait keeps the cycle's place, the cycle's pace follows his speed,
## and his facing doesn't flicker on a line between two of the 8 directions.
## godot --headless --path game -s res://tests/gait_test.gd


func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(0.5).timeout
	m.state = 5  # HALF_TIME with a long pause: nobody's AI moves them
	m._state_left = 1e9
	var ok := true
	var p = m.home.players[5]

	# S-2-AC1: a gait holds a little past its threshold (120 px/s, run over jog) either way
	var gaits := []
	for g_speed in [["run", 115.0], ["run", 105.0], ["jog", 125.0], ["jog", 135.0], ["xstandd", 4.0], ["walk", 4.7], ["walk", 0.0]]:
		p._gait = g_speed[0]
		p._gait_for = 1.0
		p.velocity = Vector2(g_speed[1], 0)
		gaits.append(p._locomotion_anim())
	print("gaits: %s" % [gaits])
	ok = ok and gaits == ["run", "jog", "jog", "run", "xstandd", "walk", "xstandd"]

	# ... and plays at least GAIT_MIN: just changed to a jog, a speed for walking keeps it a jog
	p._gait = "jog"
	p._gait_for = 0.1
	p.velocity = Vector2(20, 0)
	var held: String = p._locomotion_anim()
	print("jog for 0.1 s at 20 px/s: %s" % held)
	ok = ok and held == "jog"

	# S-2-AC1: a run turning into a jog keeps the cycle's place; standing after a kick starts it
	p._play("run")
	p._anim_time = 0.5
	p._play("jog")
	var kept: float = p._anim_time
	p._play_action("kick")
	p._play("xstandd")
	print("run -> jog keeps %.2f s; after a kick %.2f s" % [kept, p._anim_time])
	ok = ok and kept == 0.5 and p._anim_time == 0.0

	# S-2-AC1: the pace follows the speed: twice the run's typical speed, faster; a crawl, slower
	p._play("run")
	var paces := []
	for speed in [165.0, 191.0, 120.0]:
		p.velocity = Vector2(speed, 0)
		paces.append(p._pace())
	p._play_action("kick")
	paces.append(p._pace())
	print("run's pace at 165, 191, 120 px/s and in a kick: %s" % [paces])
	ok = ok and is_equal_approx(paces[0], 1.0) and paces[1] > 1.1 and paces[2] < 0.8 and paces[3] == 1.0

	# S-2-AC1: facing up-right (2... 1) only once the heading is well past the line between them
	var anims = root.get_node("Anims")
	var at := func(deg: float) -> Vector2: return Vector2.UP.rotated(deg_to_rad(deg))
	var facings := [anims.facing_from(at.call(25.0)), anims.facing_from(at.call(25.0), 0),
		anims.facing_from(at.call(35.0), 0), anims.facing_from(at.call(-25.0), 0)]
	print("facing at 25 deg: %d free, %d held at up; 35 deg held: %d; -25 held: %d" % facings)
	ok = ok and facings == [1, 0, 1, 0]

	print("GAIT TEST %s" % ("PASSED" if ok else "FAILED"))
	quit()
