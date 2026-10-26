extends SceneTree
## The 3D edition (slice 2, S-3 and S-4, ADR-005): PLAYERS cycles Pixel, Rendered and 3D; in 3D
## each player, the referee and the ball have a 3D body posed from what the sprite would show,
## in their kit, the sprite hidden; every animation the game plays has a pose; they turn
## smoothly; replays pose them too.
## godot --headless --path game -s res://tests/solid_test.gd


func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var puppet_script: GDScript = load("res://scripts/puppet.gd")
	var px: float = load("res://scripts/pitch.gd").PX_PER_M
	var ok := true

	# S-4-AC1: the cycle, and the Rendered font with 3D
	var arts := []
	for art in 3:
		match_script.set_player_art(art)
		arts.append([match_script.player_art(), match_script.rendered, match_script.solid])
	print("player art: %s" % [arts])
	ok = ok and arts == [[0, false, false], [1, true, false], [2, true, true]]

	match_script.replays_on = false
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(1.0).timeout

	# S-4-AC2: everyone has a body in the stadium, where he is, and no sprite
	var actors: Array = m.home.players + m.away.players + [m.referee]
	var placed := 0
	for p in actors:
		var q = p.puppet
		if q and q.get_parent() == m.stadium and q.visible and not p._sprite.visible \
				and q.position.distance_to(Vector3(p.position.x, 0, p.position.y) / px) < 0.5:
			placed += 1
	var ball_ok: bool = m.ball.puppet != null and m.ball.puppet.visible and not m.ball._sprite.visible
	print("bodies placed: %d of %d; the ball's %s" % [placed, actors.size(), ball_ok])
	ok = ok and placed == actors.size() and ball_ok

	# S-3-AC2: in the kit's colours, the shirt striped in its two
	var p0 = m.home.players[1]
	var colours := {}
	for mesh in p0.puppet.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat: ShaderMaterial = mesh.get_surface_override_material(i)
			colours[mesh.mesh.surface_get_material(i).resource_name] = [mat.get_shader_parameter("colour"), mat.get_shader_parameter("stripe")]
	var kit: ShaderMaterial = m.home.outfield_material
	var shirt: Vector3 = kit.get_shader_parameter("shirt")
	var shorts: Vector3 = kit.get_shader_parameter("shorts")
	print("slots: %s" % [colours.keys()])
	ok = ok and colours.size() == 7 and colours.striped[0] == Color(shirt.x, shirt.y, shirt.z) \
		and colours.striped[1] > 0.0 and colours.shorts[0] == Color(shorts.x, shorts.y, shorts.z)

	# S-4-AC4: every animation the game knows, and the referee's, has a pose the model has
	var library: Array = p0.puppet.animations()
	var names: Array = root.get_node("Anims").names() + m.referee.anim_names.values()
	var missing := names.filter(func(n): return puppet_script.pose_for(n, library) not in library)
	print("%d poses for %d animations; without one: %s" % [library.size(), names.size(), missing])
	ok = ok and missing.is_empty() and library.size() == 50

	# S-4-AC3: a turn about is smooth, at Puppet.TURN
	var q = p0.puppet
	var l: Array = p0.look()
	l[4] = 0
	for i in 30:
		q.show_look(l, 1.0)
	var before: float = q._heading
	l[4] = 4
	q.show_look(l, 1.0)
	var step: float = absf(angle_difference(before, q._heading))
	print("a turn about: %.2f rad in one frame (TURN %.1f rad/s)" % [step, puppet_script.TURN])
	ok = ok and step > 0.0 and step < 0.5

	# S-4-AC6: the giant players modifier scales the body
	q.show_look(l, 1.6)
	print("giant: scale %.1f" % q.scale.x)
	ok = ok and is_equal_approx(q.scale.x, 1.6)

	q.show_look(l, 1.0)

	# S-5-AC1: the run is the model's sprint, its cycle going on by the ground covered
	var run: Array = p0.look()
	run[1] = "run"
	run[3] = true
	q.show_look(run, 1.0)
	var from: float = q._stride
	run[0] = run[0] + Vector2(puppet_script.STRIDE.sprint * px * 0.25, 0)  # 0.25 s of the drawn pace's ground
	q.show_look(run, 1.0)
	print("run plays %s; %.2f s on for its stride's ground" % [q._player.assigned_animation, q._stride - from])
	ok = ok and q._player.assigned_animation == "sprint" and is_equal_approx(q._stride - from, 0.25)

	# S-5-AC2: a kick fades in from the run, then is the kick
	var kick: Array = run.duplicate()
	kick[1] = "kick"
	kick[2] = 0.0
	kick[3] = false
	var anim: Animation = q._player.get_animation("kick")
	var hip: Node3D = q.find_child("hipR", true, false)
	var track := anim.find_track(q._player.get_node(q._player.root_node).get_path_to(hip), Animation.TYPE_ROTATION_3D)
	q.show_look(kick, 1.0)
	var off_at_once := hip.quaternion.angle_to(anim.rotation_track_interpolate(track, 0.0))
	for i in 6:
		kick[2] += 0.05
		q.show_look(kick, 1.0)
	var off_later := hip.quaternion.angle_to(anim.rotation_track_interpolate(track, kick[2]))
	print("kick's hip: %.2f rad off it at once, %.3f after 0.3 s" % [off_at_once, off_later])
	ok = ok and off_at_once > 0.05 and off_later < 0.01

	# S-4-AC5: a replay poses the bodies as they were, not as they are
	await create_timer(3.0).timeout
	var r = m.replay
	r.play(2.0, 1.0, false)
	await process_frame
	await process_frame
	var frame: Array = r.clip[int(r.at)]
	var replayed := 0
	for a in frame[2]:
		if a[0].puppet.position.distance_to(Vector3(a[1][0].x, 0, a[1][0].y) / px) < 0.01:
			replayed += 1
	print("replay: %d of %d bodies where the frame has them" % [replayed, frame[2].size()])
	ok = ok and replayed == frame[2].size() and replayed > 0
	r.stop()
	await process_frame

	# back to Pixel: bodies hidden, sprites back
	match_script.set_player_art(0)
	await process_frame
	var hidden := actors.all(func(p): return not p.puppet.visible and p._sprite.visible)
	print("back to Pixel: bodies hidden, sprites shown %s" % hidden)
	ok = ok and hidden

	print("SOLID TEST %s" % ("PASSED" if ok else "FAILED"))
	quit()
