extends SceneTree
## The referee draws with his own art (assets/sprites/oscf_roles), not the FIFA 96 players':
## he stands, runs, blows the whistle, points and shows a yellow or red card.
## godot --headless --path game -s res://tests/referee_art_test.gd

func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(0.3).timeout
	var ok := true
	var ref = m.referee
	var anims: Node = root.get_node("Anims")  # not named in code: see classic_test.gd

	var art := ["ref_idle", "ref_run", "ref_whistle", "ref_card", "ref_point"].filter(func(a): return anims.has(a))
	print("referee animations loaded: %s" % [art])
	ok = ok and art.size() == 5

	var sprite: Sprite2D = ref._sprite
	print("referee material: %s" % [sprite.material.shader.resource_path])
	ok = ok and sprite.material.shader.resource_path.ends_with("referee_card.gdshader")

	var looks := []  # what his locomotion plays at a run, a jog, a walk and standing still
	for speed in [200.0, 80.0, 20.0, 0.0]:  # the match steers him every frame, so not via wish
		ref.velocity = Vector2(speed, 0.0)
		ref._play(ref._locomotion_anim())
		looks.append(ref._anim)
	print("run, jog, walk, stand: %s" % [looks])
	ok = ok and looks == ["ref_run", "ref_run", "ref_run", "ref_idle"]

	m.play_sfx("whistle")
	var whistle: String = ref._anim
	await create_timer(anims.length_seconds("ref_whistle") + 0.1).timeout
	m.book(m.away.players[7], false)
	var yellow: Color = sprite.material.get_shader_parameter("card")
	var card: String = ref._anim
	await create_timer(anims.length_seconds("ref_card") + 0.1).timeout
	m.book(m.away.players[7], false)  # a second yellow
	var red: Color = sprite.material.get_shader_parameter("card")
	print("whistle: %s; card: %s, first %s, second %s" % [whistle, card, yellow.to_html(false), red.to_html(false)])
	ok = ok and whistle == "ref_whistle" and card == "ref_card" \
		and yellow.is_equal_approx(m.YELLOW_CARD) and red.is_equal_approx(m.RED_CARD)

	print("REFEREE ART TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
